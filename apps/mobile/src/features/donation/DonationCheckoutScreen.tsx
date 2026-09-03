import React from 'react';
import {StyleSheet, Text, View} from 'react-native';
import {useMutation, useQuery} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {Button, Card, ErrorState, Loading, Muted, ScrollScreen, SectionTitle, TextField, Title} from '../../components/UI';
import {colors, space, type} from '../../theme/tokens';
import type {DonationResult, PaymentMethod} from '../../types/domain';
import type {RootStackScreenProps} from '../../navigation/types';

const presets = [50000, 100000, 250000, 500000];

export default function DonationCheckoutScreen({route}: RootStackScreenProps<'DonationCheckout'>) {
  const campaign = route.params.campaign;
  const [amount, setAmount] = React.useState('100000');
  const [name, setName] = React.useState('');
  const [email, setEmail] = React.useState('');
  const [message, setMessage] = React.useState('');
  const [method, setMethod] = React.useState('');
  const [result, setResult] = React.useState<DonationResult | null>(null);
  const methods = useQuery({queryKey: ['payment-methods'], queryFn: () => api<PaymentMethod[]>('/api/v1/donation/payment-methods')});
  React.useEffect(() => { if (methods.data?.length && !method) setMethod(methods.data[0].method_code); }, [methods.data, method]);
  const mutation = useMutation({
    mutationFn: () => api<DonationResult>('/api/v1/donations', {
      method: 'POST',
      headers: {'Idempotency-Key': `${Date.now()}-${Math.random().toString(36).slice(2)}`},
      body: JSON.stringify({campaign_id: campaign.id, donor_name: name, donor_email: email, anonymous: false, message, amount: Number(amount), payment_method: method}),
    }),
    onSuccess: setResult,
  });
  const selected = methods.data?.find(item => item.method_code === method);

  return (
    <ScrollScreen safeTop={false}>
      <Title>Konfirmasi donasi</Title>
      <Muted>{campaign.name}</Muted>
      {result ? (
        <>
          <Card style={styles.successCard}>
            <Text style={styles.success}>Transaksi berhasil dibuat</Text>
            <Muted>ID transaksi</Muted><Text selectable style={styles.id}>{result.id}</Text>
            <Muted>Status: {result.status || 'WAITING_PAYMENT'}</Muted>
          </Card>
          {selected ? <Card><Text style={styles.heading}>{selected.display_name}</Text>{selected.bank_name ? <Text style={styles.body}>{selected.bank_name}</Text> : null}{selected.account_number ? <Text selectable style={styles.account}>{selected.account_number}</Text> : null}{selected.account_holder ? <Muted>a.n. {selected.account_holder}</Muted> : null}{selected.instructions ? <Text style={styles.instructions}>{selected.instructions}</Text> : null}</Card> : null}
          <Muted>Status pembayaran tetap divalidasi backend. Simpan bukti transaksi sampai proses verifikasi selesai.</Muted>
        </>
      ) : (
        <>
          <SectionTitle>Nominal</SectionTitle>
          <View style={styles.presets}>{presets.map(value => <View key={value} style={styles.preset}><Button secondary={Number(amount) !== value} title={`Rp ${value.toLocaleString('id-ID')}`} onPress={() => setAmount(String(value))} /></View>)}</View>
          <TextField label="Nominal lainnya" keyboardType="numeric" value={amount} onChangeText={setAmount} placeholder="100000" />
          <SectionTitle>Data donor</SectionTitle>
          <TextField label="Nama" value={name} onChangeText={setName} placeholder="Opsional" />
          <TextField label="Email" value={email} onChangeText={setEmail} autoCapitalize="none" keyboardType="email-address" placeholder="Opsional" />
          <TextField label="Doa / pesan" value={message} onChangeText={setMessage} multiline style={{minHeight: 88, textAlignVertical: 'top'}} placeholder="Opsional" />
          <SectionTitle>Metode pembayaran</SectionTitle>
          {methods.isLoading ? <Loading /> : null}
          {methods.isError ? <ErrorState message={userMessage(methods.error)} onRetry={() => methods.refetch()} /> : null}
          {methods.data?.map(item => <Button key={item.method_code} secondary={method !== item.method_code} title={item.display_name} onPress={() => setMethod(item.method_code)} />)}
          {mutation.error ? <ErrorState message={userMessage(mutation.error)} /> : null}
          <Button disabled={!method || Number(amount) <= 0 || mutation.isPending} title={mutation.isPending ? 'Membuat transaksi...' : 'Buat transaksi'} onPress={() => mutation.mutate()} />
        </>
      )}
    </ScrollScreen>
  );
}

const styles = StyleSheet.create({
  presets: {flexDirection: 'row', flexWrap: 'wrap', gap: space.sm},
  preset: {width: '48%'},
  successCard: {marginTop: space.lg, borderColor: '#BBDDCB'},
  success: {...type.section, color: colors.success, marginBottom: space.md},
  id: {...type.caption, color: colors.text, marginVertical: space.xs},
  heading: {...type.bodyStrong, color: colors.text},
  body: {...type.body, color: colors.text},
  account: {fontSize: 23, lineHeight: 29, fontWeight: '900', color: colors.primary, marginVertical: space.sm},
  instructions: {...type.body, color: colors.text, marginTop: space.md},
});
